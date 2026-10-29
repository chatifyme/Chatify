import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    name: 'extension',
    environment: 'node',
    include: ['{config,i18n}/**/*.test.ts'],
  },
});
