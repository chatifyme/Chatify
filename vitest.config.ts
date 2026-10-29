import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    projects: ['shared', 'extension'],
    coverage: {
      provider: 'v8',
      include: ['shared/src/**', 'extension/{config,i18n}/**'],
    },
  },
});
