import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['**/node_modules/**', '**/.output/**', '**/.wxt/**', '**/coverage/**', '**/dist/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['extension/**/*.{ts,tsx}'],
    plugins: { 'react-hooks': reactHooks },
    rules: reactHooks.configs.recommended.rules,
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['*.{js,ts}', '**/*.config.{js,ts}'],
    languageOptions: { globals: globals.node },
  },
  prettier,
);
