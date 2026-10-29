/**
 * The only sites Chatify may run on. Content script matches and host_permissions
 * both come from here, so adding a site is a single, reviewable change.
 * Never add <all_urls> (see CLAUDE.md, extension rules).
 */
export const AI_TOOL_HOSTS = ['https://chatgpt.com/*', 'https://chat.openai.com/*'] as const;
