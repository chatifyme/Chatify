import ReactDOM from 'react-dom/client';
import { Badge } from '../../ui/Badge';
import '../../assets/tailwind.css';

export default defineContentScript({
  matches: ['https://chatgpt.com/*', 'https://chat.openai.com/*'],
  cssInjectionMode: 'ui',

  async main(ctx) {
    // Static message only. Never log prompt content (see CLAUDE.md privacy rules).
    console.info('[Chatify] content script active');

    const ui = await createShadowRootUi(ctx, {
      name: 'chatify-badge',
      position: 'inline',
      anchor: 'body',
      onMount: (container) => {
        const root = ReactDOM.createRoot(container);
        root.render(<Badge />);
        return root;
      },
      onRemove: (root) => root?.unmount(),
    });
    ui.mount();
  },
});
