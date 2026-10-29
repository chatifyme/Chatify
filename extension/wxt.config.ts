import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'wxt';
import { AI_TOOL_HOSTS } from './config/hosts';
import { hr } from './i18n/hr';

export default defineConfig({
  modules: ['@wxt-dev/module-react'],
  manifest: {
    name: 'Chatify',
    description: hr['manifest.description'],
    host_permissions: [...AI_TOOL_HOSTS],
    permissions: [],
  },
  vite: () => ({
    plugins: [tailwindcss()],
  }),
});
