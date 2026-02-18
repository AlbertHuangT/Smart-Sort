const { withInfoPlist, withAndroidManifest } = require('expo/config-plugins');

const ensureUsesPermission = (androidManifest, permission) => {
  const usesPermissions = androidManifest.manifest['uses-permission'] || [];
  const alreadyHas = usesPermissions.some(
    (item) => item.$ && item.$['android:name'] === permission
  );
  if (!alreadyHas) {
    usesPermissions.push({ $: { 'android:name': permission } });
    androidManifest.manifest['uses-permission'] = usesPermissions;
  }
};

module.exports = function withReactNativeContacts(config, options = {}) {
  config = withInfoPlist(config, (config) => {
    config.modResults.NSContactsUsageDescription =
      options.contactsPermission ||
      config.modResults.NSContactsUsageDescription ||
      'Allow The Trash to access contacts to match friends.';
    return config;
  });

  config = withAndroidManifest(config, (config) => {
    ensureUsesPermission(config.modResults, 'android.permission.READ_CONTACTS');
    ensureUsesPermission(
      config.modResults,
      'android.permission.WRITE_CONTACTS'
    );
    return config;
  });

  return config;
};
