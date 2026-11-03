import ReactDOM from 'react-dom/client';
import { Badge } from '../../ui/Badge';
import '../../assets/tailwind.css';
import { onTextChange } from '../../adapters/chatgpt';

export default defineContentScript({
  matches: ['https://chatgpt.com/*', 'https://chat.openai.com/*'],
  cssInjectionMode: 'ui',

  async main(ctx) {
    // Static message only. Never log prompt content (see CLAUDE.md privacy rules).
    console.info('[Chatify] content script active');

    if (import.meta.env.DEV) {
      // Dev only: log the size of the prompt, never its content.
      const stopWatching = onTextChange((text) => {
        console.info(
          `[Chatify] input changed: ${text.length} chars, ${text.split('\n').length} lines`,
        );
      });
      ctx.onInvalidated(stopWatching);
    }

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
