module.exports = {
  root: true,
  extends: ['universe/native'],
  ignorePatterns: ['node_modules/', 'dist/', 'build/'],
  settings: {
    'import/resolver': {
      node: {
        extensions: ['.js', '.jsx'],
        moduleDirectory: ['node_modules', '.']
      }
    }
  },
  rules: {
    'import/no-unresolved': ['error', { ignore: ['^expo-router/entry'] }],
    'no-console': ['warn', { allow: ['warn', 'error', 'log'] }]
  }
};
