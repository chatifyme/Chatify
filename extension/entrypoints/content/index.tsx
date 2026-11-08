import ReactDOM from 'react-dom/client';
import { Badge } from '../../ui/Badge';
import { FallbackBox } from '../../ui/FallbackBox';
import { onInputPresence, onTextChange } from '../../adapters/chatgpt';
import { createFallbackWatchdog } from '../../adapters/fallback';
import '../../assets/tailwind.css';

const FALLBACK_TIMEOUT_MS = 3000;

/** Dev only: logs the size of a prompt, never its content. */
function logPromptSize(text: string): void {
  console.info(
    `[Chatify] input changed: ${text.length} chars, ${text.split('\n').length} lines`,
  );
}

export default defineContentScript({
  matches: ['https://chatgpt.com/*', 'https://chat.openai.com/*'],
  cssInjectionMode: 'ui',

  async main(ctx) {
    // Static message only. Never log prompt content (see CLAUDE.md privacy rules).
    console.info('[Chatify] content script active');

    const badge = await createShadowRootUi(ctx, {
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
    badge.mount();

    const fallback = await createShadowRootUi(ctx, {
      name: 'chatify-fallback',
      position: 'inline',
      anchor: 'body',
      onMount: (container) => {
        const root = ReactDOM.createRoot(container);
        root.render(
          <FallbackBox
            onTextChange={(text) => {
              if (import.meta.env.DEV) logPromptSize(text);
            }}
          />,
        );
        return root;
      },
      onRemove: (root) => root?.unmount(),
    });

    // Show the fallback box if the input stays missing; hide it when the input returns.
    const watchdog = createFallbackWatchdog({
      timeoutMs: FALLBACK_TIMEOUT_MS,
      onMissing: () => fallback.mount(),
      onFound: () => fallback.remove(),
    });
    const stopPresence = onInputPresence((found) => watchdog.check(found));
    ctx.onInvalidated(() => {
      stopPresence();
      watchdog.stop();
    });

    if (import.meta.env.DEV) {
      ctx.onInvalidated(onTextChange(logPromptSize));
    }
  },
});
