import sonarjs from 'eslint-plugin-sonarjs';

// QUAL-01C: optional independent analysis. A plugin failure must not suppress core ESLint.
export default [{
  files: ['**/*.js', '**/*.mjs'],
  ignores: ['node_modules/**', 'assets/**', 'supabase/**'],
  languageOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  plugins: { sonarjs },
  rules: { 'sonarjs/cognitive-complexity': ['warn', 15] },
}];
