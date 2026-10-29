import { AI_TOOL_HOSTS } from '../config/hosts';

export default defineContentScript({
  matches: [...AI_TOOL_HOSTS],
  main() {
    // Phase 0 only proves the script is injected. No prompt text is read yet.
    console.info('[Chatify] content script active');
  },
});
