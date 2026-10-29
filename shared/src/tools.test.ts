import { describe, expect, it } from 'vitest';
import { toolSchema } from './tools';

describe('toolSchema', () => {
  it('accepts a supported tool', () => {
    expect(toolSchema.parse('chatgpt')).toBe('chatgpt');
  });

  it('rejects an unknown tool', () => {
    expect(toolSchema.safeParse('unknown').success).toBe(false);
  });
});
