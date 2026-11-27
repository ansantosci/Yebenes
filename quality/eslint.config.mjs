import sonarjs from 'eslint-plugin-sonarjs';

// QUAL-01A: observational rules; historical findings do not fail deployment.
export default [
  {
    files: ['**/*.js', '**/*.mjs'],
    ignores: ['node_modules/**', 'assets/**', 'supabase/**'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
    },
    plugins: { sonarjs },
    rules: {
      'sonarjs/cognitive-complexity': ['warn', 15],
      'no-unreachable': 'warn',
      'no-constant-condition': 'warn',
      'no-dupe-args': 'warn',
      'no-dupe-else-if': 'warn',
      'no-duplicate-case': 'warn',
      'no-func-assign': 'warn',
      'no-unsafe-finally': 'warn',
      'complexity': ['warn', { max: 15 }],
    },
  },
];
