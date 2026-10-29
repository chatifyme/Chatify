import { defineConfig } from 'wxt';
import tailwindcss from '@tailwindcss/vite';

// Only AI-tool domains. Never <all_urls> (see CLAUDE.md).
export default defineConfig({
  modules: ['@wxt-dev/module-react'],
  vite: () => ({ plugins: [tailwindcss()] }),
  manifest: {
    name: 'Chatify',
    description: 'Bolji promptovi i zaštita osjetljivih podataka u AI alatima.',
    permissions: [],
    host_permissions: ['https://chatgpt.com/*', 'https://chat.openai.com/*'],
  },
});
