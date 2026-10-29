import { describe, expect, it } from 'vitest';
import { AI_TOOL_HOSTS } from './hosts';

describe('AI_TOOL_HOSTS', () => {
  it('lists exactly the ChatGPT domains', () => {
    expect(AI_TOOL_HOSTS).toEqual(['https://chatgpt.com/*', 'https://chat.openai.com/*']);
  });

  it('never grants broad access', () => {
    for (const host of AI_TOOL_HOSTS) {
      expect(host).not.toContain('<all_urls>');
      expect(host).toMatch(/^https:\/\/[a-z0-9.-]+\/\*$/);
      expect(host).not.toMatch(/^https:\/\/\*/);
    }
  });
});
